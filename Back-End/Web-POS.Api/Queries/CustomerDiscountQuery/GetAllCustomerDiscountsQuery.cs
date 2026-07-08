using MediatR;
using FluentValidation;
using Api.Models;
using Api.Repository;
using Api.Helpers;

namespace Api.Queries.CustomerDiscountQuery
{
    public class GetAllCustomerDiscountsQuery : IRequest<List<CustomerDiscountDto>>
    {
        public int CompanyId { get; set; }

        public class GetAllCustomerDiscountsQueryValidator : AbstractValidator<GetAllCustomerDiscountsQuery>
        {
            public GetAllCustomerDiscountsQueryValidator()
            {
                RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID is required.");
            }
        }

        public class GetAllCustomerDiscountsQueryHandler : IRequestHandler<GetAllCustomerDiscountsQuery, List<CustomerDiscountDto>>
        {
            private readonly CustomerDiscountRepository _repository;

            public GetAllCustomerDiscountsQueryHandler(CustomerDiscountRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<CustomerDiscountDto>> Handle(GetAllCustomerDiscountsQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetAllAsync(request.CompanyId);
                return entities.Select(MapperCustomerDiscount.MapToDto).ToList();
            }
        }
    }
}