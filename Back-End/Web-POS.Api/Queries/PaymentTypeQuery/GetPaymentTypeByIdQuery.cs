using FluentValidation;
using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.PaymentTypeQuery
{
    public class GetPaymentTypeByIdQuery : IRequest<PaymentTypeDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

        public class GetPaymentTypeByIdQueryHandler : IRequestHandler<GetPaymentTypeByIdQuery, PaymentTypeDto?>
        {
            private readonly PaymentTypeRepository _repository;

            public GetPaymentTypeByIdQueryHandler(PaymentTypeRepository repository)
            {
                _repository = repository;
            }

            public async Task<PaymentTypeDto?> Handle(GetPaymentTypeByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id, request.CompanyId);
                return entity == null ? null : MapperPaymentType.MapToPaymentTypeDto(entity);
            }
        }
    }
    public class GetPaymentTypeByIdQueryValidator : AbstractValidator<GetPaymentTypeByIdQuery>
    {
        public GetPaymentTypeByIdQueryValidator()
        {
            RuleFor(x => x.Id).GreaterThan(0).WithMessage("Payment Type ID must be valid.");
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}