using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;
using MediatR;

namespace Products.Api.Queries.ApplicationPropertyQuery
{
    public class GetAllApplicationPropertiesQuery : IRequest<List<ApplicationPropertyDto>>
    {
        public int CompanyId { get; set; }
        public class GetAllApplicationPropertiesQueryHandler: IRequestHandler<GetAllApplicationPropertiesQuery, List<ApplicationPropertyDto>>
        {
            private readonly ApplicationPropertyRepository _repository;
            public GetAllApplicationPropertiesQueryHandler(ApplicationPropertyRepository repository)
            {
                _repository = repository;
            }
            public async Task<List<ApplicationPropertyDto>> Handle(GetAllApplicationPropertiesQuery request, CancellationToken cancellationToken)
            {
                var list = await _repository.GetAllAsync(request.CompanyId);
                return list.Select(MapperApplicationProperty.MapToApplicationPropertyDto).ToList();
            }
        }
    }
}
