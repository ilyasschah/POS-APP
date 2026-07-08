using MediatR;
using FluentValidation;
using Api.Models;
using Api.Repository;

namespace Api.Queries.MenuQuery
{
    public class GetFullMenuQuery : IRequest<List<MenuCategoryDto>>
    {
        public int CompanyId { get; set; }
        public int WarehouseId { get; set; }

        // --- VALIDATOR ---
        public class GetFullMenuQueryValidator : AbstractValidator<GetFullMenuQuery>
        {
            public GetFullMenuQueryValidator()
            {
                RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
                RuleFor(x => x.WarehouseId).GreaterThan(0).WithMessage("Warehouse ID must be valid to fetch correct stock.");
            }
        }

        // --- HANDLER ---
        public class GetFullMenuQueryHandler : IRequestHandler<GetFullMenuQuery, List<MenuCategoryDto>>
        {
            private readonly MenuRepository _repository;

            public GetFullMenuQueryHandler(MenuRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<MenuCategoryDto>> Handle(GetFullMenuQuery request, CancellationToken cancellationToken)
            {
                return await _repository.GetFullMenuAsync(request.CompanyId, request.WarehouseId);
            }
        }
    }
}