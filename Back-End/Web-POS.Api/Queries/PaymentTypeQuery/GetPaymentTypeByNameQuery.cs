using FluentValidation;
using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.PaymentTypeQuery
{
    public class GetPaymentTypeByNameQuery : IRequest<PaymentTypeDto?>
    {
        public string Name { get; set; }
        public int CompanyId { get; set; }

        public class GetPaymentTypeByNameQueryHandler : IRequestHandler<GetPaymentTypeByNameQuery, PaymentTypeDto?>
        {
            private readonly PaymentTypeRepository _repository;

            public GetPaymentTypeByNameQueryHandler(PaymentTypeRepository repository)
            {
                _repository = repository;
            }

            public async Task<PaymentTypeDto?> Handle(GetPaymentTypeByNameQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByNameAsync(request.Name, request.CompanyId);
                return entity == null ? null : MapperPaymentType.MapToPaymentTypeDto(entity);
            }
        }
    }
    public class GetPaymentTypeByNameQueryValidator : AbstractValidator<GetPaymentTypeByNameQuery>
    {
        public GetPaymentTypeByNameQueryValidator()
        {
            RuleFor(x => x.Name).NotEmpty().WithMessage("Payment Type Name must be provided.");
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}