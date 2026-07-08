using MediatR;
using FluentValidation;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.PosOrderItemQuery
{
    public class GetPosOrderItemByIdQuery : IRequest<PosOrderItemDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

        // --- VALIDATOR ---
        public class GetPosOrderItemByIdQueryValidator : AbstractValidator<GetPosOrderItemByIdQuery>
        {
            public GetPosOrderItemByIdQueryValidator()
            {
                RuleFor(x => x.Id)
                    .GreaterThan(0).WithMessage("Item ID must be greater than zero.");

                RuleFor(x => x.CompanyId)
                    .GreaterThan(0).WithMessage("Company ID must be valid.");
            }
        }

        // --- HANDLER ---
        public class GetPosOrderItemByIdQueryHandler : IRequestHandler<GetPosOrderItemByIdQuery, PosOrderItemDto?>
        {
            private readonly PosOrderItemRepository _repository;

            public GetPosOrderItemByIdQueryHandler(PosOrderItemRepository repository)
            {
                _repository = repository;
            }

            public async Task<PosOrderItemDto?> Handle(GetPosOrderItemByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id, request.CompanyId);

                if (entity == null)
                    return null;

                return MapperPosOrderItem.MapToPosOrderItemDto(entity);
            }
        }
    }
}